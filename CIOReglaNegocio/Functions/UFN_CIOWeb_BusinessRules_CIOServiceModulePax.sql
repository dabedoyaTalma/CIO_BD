/****** Object:  UserDefinedFunction [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CIOServiceModulePax]    Script Date: 23/05/2023 8:36:49 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================================================================================================
-- Description: Function for Businees Rules "ATENCION PAX EN MODULO VLO"
--
-- Change History:
--	2019-10-29  ??: Stored Procedure created
--	2021-02-15	Sebastián Jaramillo: Inclusión RN Nueva PSO LATAM
--	2021-06-30	Sebastián Jaramillo: Inclusión RN Nueva AXM LATAM
--	2021-11-03	Sebastián Jaramillo: Inclusión RN Nueva EYP LATAM
--	2021-12-13	Diomer Alexander   : Inclusión RN Nueva AXM, CUC
--	2021-01-28	Sebastián Jaramillo: Ajuste RN LATAM se diferencia cancelaciones saliendo
--	2022-02-28	Sebastián Jaramillo: Nueva RN Ultra Air
--	2022-02-28	Sebastián Jaramillo: Se incluye RN bases nuevas VivaAir NVA, AXM, VVC, PSO, VUP
--	2022-11-11	Sebastián Jaramillo: Se incluye RN para el cliente Aerolineas Argentinas
--	2022-11-16	Sebastián Jaramillo: Se incluye RN base MTR en Ultra Air que no estaba notificada que iniciaba el 8 de oct
--	2022-11-21	Sebastián Jaramillo: Se incluye RN base CUC en Ultra Air que inició el 8 de diciembre
--	2023-02-13	Sebastián Jaramillo: Se incluye RN para cobrar por "default" 1 hora hombre adicional agente pax de ARAJET
--	2023-03-30	Sebastián Jaramillo: Inclusión RN Nueva RCH LATAM
-- =============================================================================================================================
ALTER FUNCTION [CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CIOServiceModulePax](
	@ServiceHeaderId BIGINT,
	@AirportId INT,
	@ServiceTypeId INT,
	@CompanyId INT,
	@BillingToCompany INT,
	@DepartureId INT,
	@IsArrivalFlightCancel BIT,
	@IsDepartureFlightCancel BIT,
	@DepartureFlightNumber VARCHAR(5),
	@HourArriveCancel DATETIME2,
	@HourDepartureCancel DATETIME2,
	@HourCancel DATETIME2,
	@DateService DATE NULL
)
RETURNS  @T_Result TABLE(ROW INT IDENTITY, AdditionalService BIT, AdditionalQuantity INT, AdditionalServiceName VARCHAR(150))
AS
BEGIN
	--Variables de prueba
	--DECLARE @ServiceHeaderId BIGINT = 27634
	--DECLARE @AirportId INT = 55
	--DECLARE @ServiceTypeId INT = 3
	--DECLARE @CompanyId INT = 60
	--DECLARE @BillingToCompany INT = 90
	--DECLARE @DepartureId INT = 3
	--DECLARE @IsArrivalFlightCancel BIT = 1
	--DECLARE @IsDepartureFlightCancel BIT = 1
	--DECLARE @DepartureFlightNumber VARCHAR(5) = '6761'
	--DECLARE @HourArriveCancel DATETIME2 = '20:22:23'
	--DECLARE @HourDepartureCancel DATETIME2 = NULL
	--DECLARE @HourCancel DATETIME2 = '20:22:23'
	--DECLARE @DateService DATE  = '2017-12-01'

	--DECLARE	@AirportCountryId INT
	--DECLARE	@DestinationCountryId INT
	DECLARE @IsInternational BIT
	DECLARE @StrNationalInternational NVARCHAR(100)

	IF (@CompanyId = 272 AND @BillingToCompany = 272) --ARAJET / ARAJET
	BEGIN
		IF (	@IsArrivalFlightCancel = 0 
			AND @ServiceTypeId IN (1, 4)  --TTO Y PRIMER VUELO
			AND	@DateService >= '2023-02-01'			
			)
		BEGIN
			IF (@IsDepartureFlightCancel = 0) --Cuando el servicio no tiene cancelación saliendo (Escenario Normal)
			BEGIN
				INSERT @T_Result VALUES (1, 1, 'HORA HOMBRE AGENTE DE SERVICIO PAX')
			END

			IF (@IsDepartureFlightCancel = 1) --Cuando el servicio tiene cancelación saliendo (Cancelación Saliendo)
			BEGIN
				INSERT @T_Result VALUES (1, 1, 'HORA HOMBRE AGENTE DE SERVICIO PAX')
			END
		END

		RETURN
	END

	IF (@CompanyId = 67 AND @BillingToCompany = 67) --AEROLINEAS ARGENTINAS / AEROLINEAS ARGENTINAS
	BEGIN
		IF (	@IsArrivalFlightCancel = 0 
			AND @ServiceTypeId IN (1, 4)  --TTO Y PRIMER VUELO
			AND	@DateService >= '2022-11-01' AND @AirportId = 12 --BOG				
			)
		BEGIN
			IF (@IsDepartureFlightCancel = 0) --Cuando el servicio no tiene cancelación saliendo (Escenario Normal)
			BEGIN
				INSERT @T_Result VALUES (1, 1, 'ATENCION PAX EN MODULO VLO')
			END

			IF (@IsDepartureFlightCancel = 1) --Cuando el servicio tiene cancelación saliendo (Cancelación Saliendo)
			BEGIN
				INSERT @T_Result VALUES (1, 1, 'ATENCION PAX EN MODULO VLO CANCELADO SALIENDO')
			END
		END

		RETURN
	END

	IF (@CompanyId = 259 AND @BillingToCompany = 259) --ULTRA AIR / ULTRA AIR
	BEGIN
		IF (	@IsArrivalFlightCancel = 0 
			AND @ServiceTypeId IN (1, 4)  --TTO Y PRIMER VUELO
			AND	(		(@DateService >= '2022-02-23' AND @AirportId = 5) --ADZ
					OR	(@DateService >= '2022-02-24' AND @AirportId IN (17, 55)) --CTG, SMR
					OR	(@DateService >= '2022-02-25' AND @AirportId = 45) --PEI
					OR	(@DateService >= '2022-10-08' AND @AirportId = 40) --MTR
					OR	(@DateService >= '2022-12-08' AND @AirportId = 18) --CUC
				)				
			)
		BEGIN
			IF (@IsDepartureFlightCancel = 0) --Cuando el servicio no tiene cancelación saliendo (Escenario Normal)
			BEGIN
				INSERT @T_Result VALUES (1, 1, 'ATENCION PAX EN MODULO VLO')
				INSERT @T_Result VALUES (1, 1, 'MANEJO DE RECAUDO PAX VLO')
			END

			IF (@IsDepartureFlightCancel = 1) --Cuando el servicio tiene cancelación saliendo (Cancelación Saliendo)
			BEGIN
				INSERT @T_Result VALUES (1, 1, 'ATENCION PAX EN MODULO VLO CANCELADO SALIENDO')
			END
		END

		RETURN
	END

	IF (@CompanyId = 69 AND @BillingToCompany = 69) --SARPA
	BEGIN
		IF (@ServiceTypeId IN (1, 4) AND @IsArrivalFlightCancel = 0 AND @DateService >= '2021-09-01') --TTO Y PRIMER VUELO
		BEGIN
			INSERT @T_Result VALUES (1, 1, 'ATENCION PAX EN MODULO VLO')
		END

		RETURN
	END

	IF (@CompanyId = 70 AND @BillingToCompany = 70) --INTERJET
	BEGIN
		IF (@ServiceTypeId IN (1, 4) AND @IsArrivalFlightCancel = 0 AND @DateService >= '2019-04-18') --TTO Y PRIMER VUELO
		BEGIN
			INSERT @T_Result VALUES (1, 1, 'ATENCION PAX EN MODULO VLO')
		END

		RETURN
	END

	IF (@CompanyId = 44 AND @BillingToCompany = 44) --LAN / LATAM
	BEGIN
		IF	@DateService <= '2018-06-30' RETURN --ANTES SE COBRABA POR PAX DESDE EL MODULO DE PAX

		IF (@DateService >= '2018-07-01' AND @ServiceTypeId IN (1, 4) AND @IsArrivalFlightCancel = 0 AND @AirportId = 5) --TTO Y PRIMER VUELO --ADZ
		BEGIN
			INSERT @T_Result VALUES (1, 1, 'ATENCION PAX EN MODULO VLO')
		END

		IF (@DateService >= '2020-11-01' AND @ServiceTypeId IN (1, 4) AND @IsArrivalFlightCancel = 0 AND @AirportId IN (18, 45, 59)) --TTO Y PRIMER VUELO --CUC, PEI, VUP
		BEGIN
			IF (@IsDepartureFlightCancel = 0) --Cuando el servicio no tiene cancelación saliendo (Escenario Normal)
			BEGIN
				INSERT @T_Result VALUES (1, 1, 'ATENCION PAX EN MODULO VLO')
				INSERT @T_Result VALUES (1, 1, 'MANEJO DE RECAUDO PAX VLO')
			END

			IF (@IsDepartureFlightCancel = 1) --Cuando el servicio tiene cancelación saliendo (Cancelación Saliendo)
			BEGIN
				INSERT @T_Result VALUES (1, 1, 'ATENCION PAX EN MODULO VLO CANCELADO SALIENDO')
			END
		END

		IF (@DateService >= '2021-02-01' AND @ServiceTypeId IN (1, 4) AND @IsArrivalFlightCancel = 0 AND @AirportId = 47) --TTO Y PRIMER VUELO --PSO
		BEGIN
			IF (@IsDepartureFlightCancel = 0) --Cuando el servicio no tiene cancelación saliendo (Escenario Normal)
			BEGIN
				INSERT @T_Result VALUES (1, 1, 'ATENCION PAX EN MODULO VLO')
				INSERT @T_Result VALUES (1, 1, 'MANEJO DE RECAUDO PAX VLO')
			END

			IF (@IsDepartureFlightCancel = 1) --Cuando el servicio tiene cancelación saliendo (Cancelación Saliendo)
			BEGIN
				INSERT @T_Result VALUES (1, 1, 'ATENCION PAX EN MODULO VLO CANCELADO SALIENDO')
			END
		END

		IF (@DateService >= '2021-06-05' AND @ServiceTypeId IN (1, 4) AND @IsArrivalFlightCancel = 0 AND @AirportId = 9) --TTO Y PRIMER VUELO --AXM
		BEGIN
			IF (@IsDepartureFlightCancel = 0) --Cuando el servicio no tiene cancelación saliendo (Escenario Normal)
			BEGIN
				INSERT @T_Result VALUES (1, 1, 'ATENCION PAX EN MODULO VLO')
				INSERT @T_Result VALUES (1, 1, 'MANEJO DE RECAUDO PAX VLO')
			END

			IF (@IsDepartureFlightCancel = 1) --Cuando el servicio tiene cancelación saliendo (Cancelación Saliendo)
			BEGIN
				INSERT @T_Result VALUES (1, 1, 'ATENCION PAX EN MODULO VLO CANCELADO SALIENDO')
			END
		END

		IF (@DateService >= '2021-10-27' AND @ServiceTypeId IN (1, 4) AND @IsArrivalFlightCancel = 0 AND @AirportId = 25) --TTO Y PRIMER VUELO --EYP
		BEGIN
			IF (@IsDepartureFlightCancel = 0) --Cuando el servicio no tiene cancelación saliendo (Escenario Normal)
			BEGIN
				INSERT @T_Result VALUES (1, 1, 'ATENCION PAX EN MODULO VLO')
				INSERT @T_Result VALUES (1, 1, 'MANEJO DE RECAUDO PAX VLO')
			END

			IF (@IsDepartureFlightCancel = 1) --Cuando el servicio tiene cancelación saliendo (Cancelación Saliendo)
			BEGIN
				INSERT @T_Result VALUES (1, 1, 'ATENCION PAX EN MODULO VLO CANCELADO SALIENDO')
			END
		END

		IF (@DateService >= '2023-03-27' AND @ServiceTypeId IN (1, 4) AND @IsArrivalFlightCancel = 0 AND @AirportId = 51) --TTO Y PRIMER VUELO --RCH
		BEGIN
			IF (@IsDepartureFlightCancel = 0) --Cuando el servicio no tiene cancelación saliendo (Escenario Normal)
			BEGIN
				INSERT @T_Result VALUES (1, 1, 'ATENCION PAX EN MODULO VLO')
				INSERT @T_Result VALUES (1, 1, 'MANEJO DE RECAUDO PAX VLO')
			END

			IF (@IsDepartureFlightCancel = 1) --Cuando el servicio tiene cancelación saliendo (Cancelación Saliendo)
			BEGIN
				INSERT @T_Result VALUES (1, 1, 'ATENCION PAX EN MODULO VLO CANCELADO SALIENDO')
			END
		END

		RETURN
	END

	IF (@CompanyId = 9 AND @BillingToCompany = 9 AND @IsArrivalFlightCancel = 0) --COPA
	BEGIN
		IF (@DateService >= '2022-06-28' AND @AirportId = 55) --SMR
		BEGIN
			IF (@ServiceTypeId IN (1, 4)) --TTO Y PRIMER VUELO
			BEGIN
				INSERT @T_Result VALUES (1, 1, 'ATENCION PAX EN MODULO VLO')
			END

			RETURN
		END

		IF (@DateService >= '2021-12-02' AND @AirportId IN (9,18)) --AXM, CUC
		BEGIN
			IF (@ServiceTypeId IN (1, 4)) --TTO Y PRIMER VUELO
			BEGIN
				INSERT @T_Result VALUES (1, 1, 'ATENCION PAX EN MODULO VLO')
			END

			RETURN
		END

		IF (@DateService >= '2020-09-01' AND @AirportId IN (5, 10, 11, 4, 17, 3, 45)) --ADZ, BAQ, BGA, CLO, CTG, MDE, PEI
		BEGIN
			IF (@ServiceTypeId IN (1, 4)) --TTO Y PRIMER VUELO
			BEGIN
				INSERT @T_Result VALUES (1, 1, 'ATENCION PAX EN MODULO VLO')
			END

			RETURN
		END

		IF (@DateService BETWEEN '2018-01-26' AND '2020-08-31' AND @AirportId = 11) --BGA
		BEGIN
			IF (@ServiceTypeId IN (1, 4)) --TTO Y PRIMER VUELO
			BEGIN
				INSERT @T_Result VALUES (1, 1, 'ATENCION PAX EN MODULO VLO')
			END

			RETURN
		END

		IF	@DateService <= '2018-01-25' 
		BEGIN
			RETURN --ANTES SE CONTABA MANUAL
		END
	END

	IF ((@CompanyId = 60 AND @BillingToCompany = 90) OR (@CompanyId = 192 AND @BillingToCompany = 192)) --VIVACOLOMBIA Y VIVAPERU
	BEGIN
		IF (	@ServiceTypeId IN (1, 2, 3, 4) AND
					(		(@DateService >= '2017-11-01' AND @AirportId IN (55, 5)) --SMR ADZ
						OR	(@DateService >= '2017-11-08' AND @AirportId IN (3, 40)) --MDE MTR
						OR	(@DateService >= '2017-11-15' AND @AirportId IN (17, 45, 11)) --CTG PEI BGA
						OR	(@DateService >= '2017-11-21' AND @AirportId = 12)	--BOG
						OR	(@DateService >= '2018-12-20' AND @AirportId = 51)	--RCH
						OR	(@DateService >= '2019-01-04' AND @AirportId = 18)	--CUC
						OR	(@DateService >= '2019-03-01' AND @AirportId = 10)	--BAQ
						OR	(@DateService >= '2019-03-05' AND @AirportId = 34)	--LET
						OR	(@DateService >= '2020-02-01' AND @AirportId = 4)	--CLO
						OR	(@DateService >= '2022-03-23' AND @AirportId = 43)	--NVA
						OR	(@DateService >= '2022-03-25' AND @AirportId = 9)	--AXM
						OR	(@DateService >= '2022-03-27' AND @AirportId = 60)	--VVC
						OR	(@DateService >= '2022-03-29' AND @AirportId = 47)	--PSO
						OR	(@DateService >= '2022-03-30' AND @AirportId = 59)	--VUP
					)	
			) 
		BEGIN
			IF (@DepartureId IS NOT NULL)
			BEGIN
				IF ([CIOServicios].[UFN_CIO_InternationalFlight](@AirportId, @DepartureId) = 1)
				BEGIN
					SET @IsInternational = 1
					SET	@StrNationalInternational = 'INTERNACIONAL'
				END
				ELSE
				BEGIN
					SET @IsInternational = 0
					SET @StrNationalInternational = 'NACIONAL'
				END
			END
			ELSE
			BEGIN
				SET @IsInternational = 0
				SET @StrNationalInternational = 'NACIONAL' --POR AHORA MANEJADO ASI EN LAS PERNOCTAS POR NO TENER COMO IDENTIFICAR EL DESTINO CUANDO SE CANCELAN
			END

			IF (@DateService >= '2018-09-26')
			BEGIN
				IF (@IsArrivalFlightCancel = 0 AND @IsDepartureFlightCancel = 0 AND @ServiceTypeId NOT IN (2, 3)) --OJO NO SE COBRA ATENCION PAX EN MODULO VLO EN LA PERNOCTA PORQUE YA SE ESTARIA COBRANDO EN EL PRIMER VUELO
				BEGIN
					INSERT @T_Result VALUES (1, 1, CONCAT('ATENCION PAX EN MODULO VLO ', @StrNationalInternational))
				END

				IF (@IsArrivalFlightCancel = 1 AND @IsDepartureFlightCancel = 1) --Cancelado (Llegando y Saliendo)
				BEGIN
					INSERT	@T_Result
					SELECT	1, 1, CONCAT('ATENCION PAX EN MODULO VLO CANCELADO ', @StrNationalInternational)
					FROM	[CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_TotalCancellation](@AirportId,@CompanyId,@BillingToCompany,@ServiceTypeId,ISNULL(@HourArriveCancel, @HourDepartureCancel),@HourCancel,@DateService,@ServiceHeaderId) as a
					WHERE	 CollectServiceType = 1
				END

				IF (@IsArrivalFlightCancel = 0 AND @IsDepartureFlightCancel = 1) --Cancelado (Saliendo)
				BEGIN
					INSERT	@T_Result
					SELECT	1, 1, CONCAT('ATENCION PAX EN MODULO VLO CANCELADO SALIENDO ', @StrNationalInternational)
					FROM	[CIOReglaNegocio].[UFN_CIOWeb_BusinessRules_CancellationDeparture](@ServiceHeaderId, @AirportId,@CompanyId,@BillingToCompany,@ServiceTypeId,@DepartureFlightNumber,@HourDepartureCancel,@HourCancel,@DateService,@ServiceHeaderId)
					WHERE	CollectServiceType = 1
				END
			END

			IF (@DateService BETWEEN '2018-06-01' AND '2018-09-25')
			BEGIN
				IF (@IsInternational = 1)
				BEGIN
					IF (@ServiceTypeId IN (2, 3))
						RETURN

					IF (@IsArrivalFlightCancel = 0 AND @IsDepartureFlightCancel = 0)
						INSERT @T_Result VALUES (1, 1, 'ATENCION PAX EN MODULO VLO INTERNACIONAL')

					IF (@IsArrivalFlightCancel = 1 AND @IsDepartureFlightCancel = 1 AND @HourCancel > DATEADD(MINUTE, -185, @HourDepartureCancel)) --Cancelado 3 Horas y 15 Minutos Internacional Antes de la hora estimada de salida
						INSERT @T_Result VALUES (1, 1, 'ATENCION PAX EN MODULO VLO CANCELADO INTERNACIONAL')

					IF (@IsArrivalFlightCancel = 0 AND @IsDepartureFlightCancel = 1 AND @HourCancel > DATEADD(MINUTE, -185, @HourDepartureCancel)) --Cancelado 3 Horas y 15 Minutos Internacional Antes de la hora estimada de salida
						INSERT @T_Result VALUES (1, 1, 'ATENCION PAX EN MODULO VLO CANCELADO SALIENDO INTERNACIONAL')
				END
				ELSE
				BEGIN
					IF (@ServiceTypeId IN (2, 3))
						RETURN

					IF (@IsArrivalFlightCancel = 0 AND @IsDepartureFlightCancel = 0)
						INSERT @T_Result VALUES (1, 1, 'ATENCION PAX EN MODULO VLO NACIONAL')
					
					IF (@IsArrivalFlightCancel = 1 AND @IsDepartureFlightCancel = 1 AND @HourCancel > DATEADD(MINUTE, -135, @HourDepartureCancel)) --Cancelado 2 Horas y 15 Minutos Nacional Antes de la hora estimada de salida
						INSERT @T_Result VALUES (1, 1, 'ATENCION PAX EN MODULO VLO CANCELADO NACIONAL')
					
					IF (@IsArrivalFlightCancel = 0 AND @IsDepartureFlightCancel = 1 AND @HourCancel > DATEADD(MINUTE, -135, @HourDepartureCancel)) --Cancelado 2 Horas y 15 Minutos Nacional Antes de la hora estimada de salida
						INSERT @T_Result VALUES (1, 1, 'ATENCION PAX EN MODULO VLO CANCELADO SALIENDO NACIONAL')
				END
			END

			IF (@DateService BETWEEN '2017-11-01' AND '2018-05-31')
			BEGIN
				IF (@ServiceTypeId IN (2, 3))
					RETURN

				INSERT @T_Result VALUES (1, 1, CONCAT('ATENCION PAX EN MODULO VLO ', @StrNationalInternational))
			END
		END
	END
	--SELECT * FROM @T_Result
	RETURN
END